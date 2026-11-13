import 'package:flutter/material.dart';
import 'contribute_product_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CommunityFeedScreen({super.key, required this.user});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final List<Map<String, dynamic>> _posts = [
    {
      'id': 1,
      'author': 'Nguyễn Hoàng Nam',
      'avatar': '👨‍⚕️',
      'time': '2 giờ trước',
      'product_name': 'Bánh Quy Bơ Đậu Phộng Hải Châu',
      'brand': 'Công ty CP Bánh kẹo Hải Châu',
      'is_warning': true,
      'allergen_badge': '🚨 Chứa Đậu phộng & Gluten',
      'content': 'Bao bì mới đổi dây chuyền có bổ sung thêm bơ đậu phộng nguyên chất. Các bạn dị ứng lạc cần kiểm tra kỹ bảng thành phần nhé!',
      'barcode': '8934561234567',
      'likes': 42,
      'is_liked': false,
      'comments': 8,
    },
    {
      'id': 2,
      'author': 'Trần Thị Mỹ Duyên',
      'avatar': '👩‍🦰',
      'time': '5 giờ trước',
      'product_name': 'Sữa Hạt Macca & Hạnh Nhân 137 Degrees',
      'brand': '137 Degrees Thailand',
      'is_warning': false,
      'allergen_badge': '✅ An toàn không Lactose (Không sữa bò)',
      'content': 'Sản phẩm thuần chay 100%, không pha sữa bò, người không dung nạp lactose uống hoàn toàn êm bụng. Đã kiểm chứng nhãn phụ!',
      'barcode': '8859012345678',
      'likes': 68,
      'is_liked': false,
      'comments': 14,
    },
    {
      'id': 3,
      'author': 'Bác sĩ Dinh dưỡng Lê Văn Minh',
      'avatar': '🧑‍⚕️',
      'time': 'Hôm qua',
      'product_name': 'Mẹo phân biệt phụ gia dẫn xuất đạm sữa & đậu nành',
      'brand': 'Chuyên mục Giáo dục Y tế NutriViet',
      'is_warning': true,
      'allergen_badge': '⚠️ Lưu ý Casein, Whey, Lecithin',
      'content': 'Lưu ý từ vựng "casein", "whey" bản chất là đạm sữa bò. Từ vựng "lecithin" trên bánh kẹo Việt Nam thường chiết xuất từ đậu nành hoặc lòng đỏ trứng gà.',
      'barcode': 'NutriViet-Edu-Tip',
      'likes': 152,
      'is_liked': false,
      'comments': 29,
    },
  ];

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF334155), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mạng Xã Hội Cộng Đồng',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng tải sản phẩm mới',
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF10B981)),
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
                    'author': widget.user['full_name'] ?? 'Tôi (Người dùng)',
                    'avatar': '👤',
                    'time': 'Vừa xong',
                    'product_name': 'Sản phẩm vừa đóng góp',
                    'brand': 'Đã gửi duyệt cộng đồng',
                    'is_warning': false,
                    'allergen_badge': '🆕 Đóng góp mới',
                    'content': 'Đã gửi ảnh chụp bao bì và bảng thành phần lên mạng xã hội cộng đồng.',
                    'barcode': 'Pending',
                    'likes': 1,
                    'is_liked': true,
                    'comments': 0,
                    'photo_label': 'Ảnh bao bì & thành phần',
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
          // Banner invite to post
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
                  child: const Text('📸', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Chia Sẻ Thực Phẩm An Toàn',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Đăng tải ảnh bao bì sản phẩm bạn vừa mua để hỗ trợ cộng đồng nhận biết.',
                        style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11),
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
                  child: const Text('Đăng ảnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Community Feed Title
          const Text(
            'Bảng Tin Mới Nhất',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          // Posts List
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
                  // Author header
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                          color: isWarning ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post['allergen_badge'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isWarning ? const Color(0xFFDC2626) : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Product title
                  Text(
                    post['product_name'],
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  if (post['brand'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Thương hiệu: ${post['brand']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Content text
                  Text(
                    post['content'],
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // Photo Card Preview
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
                        color: isWarning ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_rounded,
                                color: isWarning ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF10B981).withValues(alpha: 0.6),
                                size: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post['photo_label'] ?? 'Ảnh chụp bao bì & thành phần thực tế',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isWarning ? const Color(0xFF991B1B) : const Color(0xFF065F46),
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
                                color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: isWarning ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  isWarning ? 'Cảnh báo nguy cơ' : 'Nhãn an toàn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isWarning ? const Color(0xFFDC2626) : const Color(0xFF059669),
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

                  // Action Buttons: Like, Comment, Share
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
                              Icon(
                                post['is_liked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: post['is_liked'] ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post['likes']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: post['is_liked'] ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF64748B), size: 16),
                          const SizedBox(width: 6),
                          Text('${post['comments']} bình luận', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Color(0xFF64748B), size: 18),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã sao chép liên kết bài viết!'), backgroundColor: Color(0xFF10B981)),
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
