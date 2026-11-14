import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import 'contribute_product_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CommunityFeedScreen({super.key, required this.user});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final List<Map<String, dynamic>> _posts = [];

  void _toggleLike(int index) {
    setState(() {
      _posts[index]['is_liked'] = !_posts[index]['is_liked'];
      if (_posts[index]['is_liked']) {
        _posts[index]['likes']++;
      } else {
        _posts[index]['likes']--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            color: Color(0xFF334155),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocale.t('Mạng Xã Hội Cộng Đồng', 'Community Network'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppLocale.t('Đăng tải sản phẩm mới', 'Post new product'),
            icon: const PhosphorIcon(
              PhosphorIconsDuotone.imagesSquare,
              color: Color(0xFF14803C),
              size: 23,
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContributeProductScreen(user: widget.user),
                ),
              );
              if (result is Map<String, dynamic>) {
                setState(() {
                  _posts.insert(0, result);
                });
              } else if (result == true) {
                setState(() {
                  _posts.insert(0, {
                    'id': DateTime.now().millisecondsSinceEpoch,
                    'author': widget.user['full_name'] ??
                        AppLocale.t('Tôi (Người dùng)', 'Me (User)'),
                    'avatar': '👤',
                    'time': AppLocale.t('Vừa xong', 'Just now'),
                    'product_name': AppLocale.t(
                      'Sản phẩm vừa đóng góp',
                      'Recently contributed product',
                    ),
                    'brand': AppLocale.t(
                      'Đã gửi duyệt cộng đồng',
                      'Submitted for community review',
                    ),
                    'is_warning': false,
                    'allergen_badge': AppLocale.t('🆕 Đóng góp mới', '🆕 New contribution'),
                    'content': AppLocale.t(
                      'Đã gửi ảnh chụp bao bì và bảng thành phần lên mạng xã hội cộng đồng.',
                      'Submitted packaging and ingredient photos to the community network.',
                    ),
                    'barcode': '',
                    'likes': 1,
                    'is_liked': true,
                    'comments': 0,
                    'photo_label': AppLocale.t(
                      'Ảnh bao bì & thành phần',
                      'Packaging & ingredient photo',
                    ),
                  });
                });
              }
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsDuotone.cameraPlus,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocale.t('Chia Sẻ Thực Phẩm An Toàn', 'Share Safe Food Products'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocale.t(
                          'Đăng tải ảnh bao bì sản phẩm bạn vừa mua để hỗ trợ cộng đồng nhận biết.',
                          'Upload packaging photos of products you bought to help the community.',
                        ),
                        style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContributeProductScreen(user: widget.user),
                      ),
                    );
                    if (result is Map<String, dynamic>) {
                      setState(() {
                        _posts.insert(0, result);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF065F46),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    AppLocale.t('Đăng ảnh', 'Post photo'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            AppLocale.t('Bảng Tin Mới Nhất', 'Latest Community Posts'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          ...List.generate(_posts.length, (index) {
            final post = _posts[index];
            final bool isWarning = post['is_warning'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(post['avatar'], style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['author'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              post['time'],
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isWarning
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post['allergen_badge'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isWarning
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    post['product_name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (post['brand'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      AppLocale.t(
                        'Thương hiệu: ${post['brand']}',
                        'Brand: ${post['brand']}',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  Text(
                    post['content'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    height: 130,
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isWarning
                            ? [const Color(0xFFFEF2F2), const Color(0xFFFFF1F2)]
                            : [const Color(0xFFF0FDF4), const Color(0xFFECFDF5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWarning
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PhosphorIcon(
                                PhosphorIconsDuotone.image,
                                color: isWarning
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                                    : const Color(0xFF14803C).withValues(alpha: 0.7),
                                size: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post['photo_label'] ??
                                    AppLocale.t(
                                      'Ảnh chụp bao bì & thành phần thực tế',
                                      'Packaging & ingredient photo',
                                    ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isWarning
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF065F46),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isWarning
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  isWarning
                                      ? PhosphorIconsFill.warningOctagon
                                      : PhosphorIconsFill.sealCheck,
                                  size: 13,
                                  color: isWarning
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF14803C),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isWarning
                                      ? AppLocale.t('Cảnh báo nguy cơ', 'Risk warning')
                                      : AppLocale.t('Nhãn an toàn', 'Safe label'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isWarning
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => _toggleLike(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              PhosphorIcon(
                                post['is_liked']
                                    ? PhosphorIconsFill.heart
                                    : PhosphorIconsDuotone.heart,
                                color: post['is_liked']
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post['likes']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: post['is_liked']
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsDuotone.chatTeardrop,
                            color: Color(0xFF64748B),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppLocale.t(
                              '${post['comments']} bình luận',
                              '${post['comments']} comments',
                            ),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const PhosphorIcon(
                          PhosphorIconsDuotone.shareNetwork,
                          color: Color(0xFF64748B),
                          size: 18,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocale.t(
                                  'Đã sao chép liên kết bài viết!',
                                  'Post link copied!',
                                ),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
