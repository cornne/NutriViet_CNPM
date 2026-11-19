import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/community_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_shimmer.dart';

/// Hidden Admin Moderation & User Management Console.
/// Only exposed in UI when `user['role'] == 'admin'` and strictly verified
/// server-side on every `/api/v1/admin/*` API call.
class AdminModerationScreen extends StatefulWidget {
  final String token;
  final int currentUserId;

  const AdminModerationScreen({
    super.key,
    required this.token,
    required this.currentUserId,
  });

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandPurple = Color(0xFF4F37C8);
  static const Color _dangerRed = Color(0xFFDC2626);

  late final TabController _tabController;
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      CommunityService.getAdminOverview(token: widget.token),
      CommunityService.getAdminReports(token: widget.token, status: 'all'),
      CommunityService.getPosts(
        token: widget.token,
        includeHidden: true,
        limit: 50,
      ),
      CommunityService.getAdminUsers(token: widget.token),
    ]);
    if (!mounted) return;

    if (results[0]['success'] != true) {
      setState(() {
        _loading = false;
        _error = results[0]['message']?.toString() ??
            AppLocale.t(
              'Không có quyền quản trị hoặc không tải được dữ liệu.',
              'Administrator access denied or unable to load data.',
            );
      });
      return;
    }

    setState(() {
      _loading = false;
      _stats = Map<String, dynamic>.from(results[0]['stats'] ?? {});
      _reports = List<Map<String, dynamic>>.from(results[1]['reports'] ?? []);
      _posts = List<Map<String, dynamic>>.from(results[2]['posts'] ?? []);
      _users = List<Map<String, dynamic>>.from(results[3]['users'] ?? []);
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _dangerRed : _brandGreen,
      ),
    );
  }

  Future<void> _handleResolveReport(int reportId, String action) async {
    final res = await CommunityService.resolveReport(
      token: widget.token,
      reportId: reportId,
      action: action,
    );
    if (res['success'] == true) {
      _showSnack(AppLocale.t('Đã xử lý báo cáo.', 'Report processed.'));
      await _loadAll();
    } else {
      _showSnack(res['message']?.toString() ?? 'Error', isError: true);
    }
  }

  Future<void> _handleModeratePost(int postId, String action) async {
    final res = await CommunityService.moderatePost(
      token: widget.token,
      postId: postId,
      action: action,
      reason: action == 'hide'
          ? AppLocale.t('Ẩn bởi quản trị viên', 'Hidden by administrator')
          : '',
    );
    if (res['success'] == true) {
      _showSnack(AppLocale.t('Đã cập nhật trạng thái bài viết.', 'Post updated.'));
      await _loadAll();
    } else {
      _showSnack(res['message']?.toString() ?? 'Error', isError: true);
    }
  }

  Future<void> _handleUpdateUser({
    required int userId,
    String? role,
    bool? isBanned,
  }) async {
    final res = await CommunityService.updateAdminUser(
      token: widget.token,
      userId: userId,
      role: role,
      isBanned: isBanned,
    );
    if (res['success'] == true) {
      _showSnack(AppLocale.t('Đã cập nhật tài khoản.', 'User account updated.'));
      await _loadAll();
    } else {
      _showSnack(res['message']?.toString() ?? 'Error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NutriVietGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsBold.caretLeft,
              color: Color(0xFF111827),
              size: 22,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.shieldCheck,
                color: _brandPurple,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocale.t('Quản trị Cộng đồng', 'Admin Moderation'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const PhosphorIcon(
                PhosphorIconsBold.arrowsClockwise,
                color: Color(0xFF111827),
                size: 20,
              ),
              onPressed: _loadAll,
            ),
          ],
        ),
        body: _loading
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  NutriVietShimmerBox(height: 82, borderRadius: 20),
                  SizedBox(height: 14),
                  NutriVietShimmerBox(height: 120, borderRadius: 20),
                  SizedBox(height: 14),
                  NutriVietShimmerBox(height: 120, borderRadius: 20),
                ],
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: NutriVietGlassCard(
                        cornerRadius: 22,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              PhosphorIconsDuotone.warningCircle,
                              color: _dangerRed,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            NutriVietGlassPillButton(
                              label: AppLocale.t('Thử lại', 'Retry'),
                              onPressed: _loadAll,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            _kpiTile(
                              AppLocale.t('Báo cáo chờ', 'Pending'),
                              '${_stats['pending_reports'] ?? 0}',
                              _dangerRed,
                            ),
                            const SizedBox(width: 8),
                            _kpiTile(
                              AppLocale.t('Bài hiện', 'Visible'),
                              '${_stats['visible_posts'] ?? 0}',
                              _brandGreen,
                            ),
                            const SizedBox(width: 8),
                            _kpiTile(
                              AppLocale.t('Đang ẩn', 'Hidden'),
                              '${_stats['hidden_posts'] ?? 0}',
                              const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            _kpiTile(
                              AppLocale.t('Tài khoản', 'Users'),
                              '${_stats['total_users'] ?? 0}',
                              _brandPurple,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: _brandPurple,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF374151),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(text: AppLocale.t('Báo cáo', 'Reports')),
                              Tab(text: AppLocale.t('Bài viết', 'Posts')),
                              Tab(text: AppLocale.t('Người dùng', 'Users')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildReportsTab(),
                            _buildPostsTab(),
                            _buildUsersTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color accent) {
    return Expanded(
      child: NutriVietGlassCard(
        cornerRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return Center(
        child: Text(
          AppLocale.t('Chưa có báo cáo vi phạm nào.', 'No reports yet.'),
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final r = _reports[idx];
        final isPending = r['status'] == 'pending';
        return NutriVietGlassCard(
          cornerRadius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (r['post_product_name'] ?? 'Post #${r['post_id'] ?? ''}').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (r['status'] ?? '').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isPending ? _dangerRed : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${AppLocale.t("Lý do", "Reason")}: ${r['reason'] ?? ''}',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 4),
              Text(
                '${AppLocale.t("Người báo cáo", "Reporter")}: ${r['reporter_name'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NutriVietGlassPillButton(
                      height: 36,
                      variant: NutriVietGlassButtonVariant.neutral,
                      label: AppLocale.t('Bỏ qua', 'Dismiss'),
                      onPressed: () => _handleResolveReport(r['id'] as int, 'dismiss'),
                    ),
                    NutriVietGlassPillButton(
                      height: 36,
                      label: AppLocale.t('Ẩn bài', 'Hide post'),
                      onPressed: () => _handleResolveReport(r['id'] as int, 'hide_post'),
                    ),
                    NutriVietGlassPillButton(
                      height: 36,
                      variant: NutriVietGlassButtonVariant.danger,
                      label: AppLocale.t('Xóa bài', 'Delete post'),
                      onPressed: () => _handleResolveReport(r['id'] as int, 'delete_post'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return Center(
        child: Text(
          AppLocale.t('Chưa có bài viết cộng đồng nào.', 'No community posts yet.'),
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final p = _posts[idx];
        final isHidden = p['status'] == 'hidden';
        return NutriVietGlassCard(
          cornerRadius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (p['product_name'] ?? '').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isHidden
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isHidden
                          ? AppLocale.t('ĐANG ẨN', 'HIDDEN')
                          : AppLocale.t('HIỂN THỊ', 'VISIBLE'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isHidden ? const Color(0xFFB45309) : _brandGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${p['author_name'] ?? ''} · ${(p['verdict'] ?? 'GREEN').toString()}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if ((p['content'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  p['content'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF374151)),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  NutriVietGlassPillButton(
                    height: 36,
                    variant: isHidden
                        ? NutriVietGlassButtonVariant.primary
                        : NutriVietGlassButtonVariant.neutral,
                    label: isHidden
                        ? AppLocale.t('Hiện lại', 'Unhide')
                        : AppLocale.t('Ẩn bài', 'Hide'),
                    onPressed: () =>
                        _handleModeratePost(p['id'] as int, isHidden ? 'unhide' : 'hide'),
                  ),
                  const SizedBox(width: 8),
                  NutriVietGlassPillButton(
                    height: 36,
                    variant: NutriVietGlassButtonVariant.danger,
                    label: AppLocale.t('Xóa vĩnh viễn', 'Delete'),
                    onPressed: () => _handleModeratePost(p['id'] as int, 'delete'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return Center(
        child: Text(
          AppLocale.t('Chưa có tài khoản nào.', 'No accounts found.'),
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, idx) {
        final u = _users[idx];
        final uid = u['id'] as int;
        final isSelf = uid == widget.currentUserId;
        final isAdmin = (u['role'] ?? 'user') == 'admin';
        final isBanned = (u['is_banned'] ?? 0) == 1;
        return NutriVietGlassCard(
          cornerRadius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u['full_name'] ?? ''}${isSelf ? " (${AppLocale.t("Bạn", "You")})" : ""}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          (u['email'] ?? '').toString(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBanned
                          ? const Color(0xFFFEE2E2)
                          : (isAdmin
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFE5F4EC)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isBanned
                          ? 'BANNED'
                          : (isAdmin ? 'ADMIN' : 'USER'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isBanned
                            ? _dangerRed
                            : (isAdmin ? _brandPurple : _brandGreen),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isSelf) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    NutriVietGlassPillButton(
                      height: 36,
                      variant: NutriVietGlassButtonVariant.neutral,
                      label: isAdmin
                          ? AppLocale.t('Hạ xuống User', 'Set User')
                          : AppLocale.t('Cấp Admin', 'Make Admin'),
                      onPressed: () => _handleUpdateUser(
                        userId: uid,
                        role: isAdmin ? 'user' : 'admin',
                      ),
                    ),
                    const SizedBox(width: 8),
                    NutriVietGlassPillButton(
                      height: 36,
                      variant: isBanned
                          ? NutriVietGlassButtonVariant.primary
                          : NutriVietGlassButtonVariant.danger,
                      label: isBanned
                          ? AppLocale.t('Mở khóa', 'Unban')
                          : AppLocale.t('Khóa tài khoản', 'Ban'),
                      onPressed: () => _handleUpdateUser(
                        userId: uid,
                        isBanned: !isBanned,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
